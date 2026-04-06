package model

import (
	"context"
	"fmt"

	"github.com/zeromicro/go-zero/core/stores/cache"
	"github.com/zeromicro/go-zero/core/stores/sqlx"
)

var _ UserRolesModel = (*customUserRolesModel)(nil)

type (
	// UserRolesModel is an interface to be customized, add more methods here,
	// and implement the added methods in customUserRolesModel.
	UserRolesModel interface {
		userRolesModel
		FindRolesByUserId(ctx context.Context, userId int64) ([]string, error)
	}

	customUserRolesModel struct {
		*defaultUserRolesModel
		conn sqlx.SqlConn
	}
)

// NewUserRolesModel returns a model for the database table.
func NewUserRolesModel(conn sqlx.SqlConn, c cache.CacheConf, opts ...cache.Option) UserRolesModel {
	return &customUserRolesModel{
		defaultUserRolesModel: newUserRolesModel(conn, c, opts...),
		conn:                  conn,
	}
}

func (m *customUserRolesModel) FindRolesByUserId(ctx context.Context, userId int64) ([]string, error) {
	var roles []string
	query := fmt.Sprintf("SELECT r.name FROM %s ur LEFT JOIN roles r ON ur.role_id = r.id WHERE ur.user_id = $1", m.table)
	err := m.conn.QueryRowsCtx(ctx, &roles, query, userId)
	return roles, err
}
